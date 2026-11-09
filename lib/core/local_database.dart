import 'dart:convert';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class LocalDatabase {
  LocalDatabase._internal();
  static final LocalDatabase instance = LocalDatabase._internal();
  factory LocalDatabase() => instance;

  static Database? _database;
  List<Map<String, dynamic>>? _inMemoryCache;
  Map<String, String>? _inMemoryKeyCache;

  Future<Database?> get database async {
    if (_database != null) return _database!;
    try {
      _database = await _initDatabase();
      return _database!;
    } catch (_) {
      return null;
    }
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'kickoff_local.db');
    final db = await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_cache (
        key TEXT PRIMARY KEY,
        json_data TEXT
      )
    ''');
    return db;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tournaments (
        id INTEGER PRIMARY KEY,
        name TEXT,
        format TEXT,
        status TEXT,
        json_data TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_cache (
        key TEXT PRIMARY KEY,
        json_data TEXT
      )
    ''');
  }

  Future<void> cacheTournaments(List<Map<String, dynamic>> tournaments) async {
    try {
      final db = await database;
      if (db == null) {
        _inMemoryCache = tournaments.map((t) => Map<String, dynamic>.from(t)).toList();
        return;
      }
      await db.transaction((txn) async {
        await txn.delete('tournaments');
        for (final tournament in tournaments) {
          await txn.insert(
            'tournaments',
            {
              'id': tournament['id'] as int?,
              'name': tournament['name'] as String?,
              'format': tournament['format'] as String?,
              'status': tournament['status'] as String?,
              'json_data': jsonEncode(tournament),
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
    } catch (_) {
      _inMemoryCache = tournaments.map((t) => Map<String, dynamic>.from(t)).toList();
    }
  }

  Future<List<Map<String, dynamic>>> getCachedTournaments() async {
    try {
      final db = await database;
      if (db == null) {
        return _inMemoryCache ?? [];
      }
      final results = await db.query('tournaments');
      return results.map((row) {
        final jsonString = row['json_data'] as String;
        return (jsonDecode(jsonString) as Map).cast<String, dynamic>();
      }).toList();
    } catch (_) {
      return _inMemoryCache ?? [];
    }
  }

  Future<Map<String, dynamic>?> getCachedTournament(int id) async {
    try {
      final db = await database;
      if (db == null) {
        final list = _inMemoryCache ?? [];
        for (final item in list) {
          if (item['id'] == id) return item;
        }
        return null;
      }
      final results = await db.query(
        'tournaments',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (results.isEmpty) return null;
      final jsonString = results.first['json_data'] as String;
      return (jsonDecode(jsonString) as Map).cast<String, dynamic>();
    } catch (_) {
      return null;
    }
  }

  Future<void> cacheTournamentDetail(int id, Map<String, dynamic> tournament) async {
    try {
      final db = await database;
      if (db == null) {
        if (_inMemoryCache != null) {
          _inMemoryCache!.removeWhere((t) => t['id'] == id);
          _inMemoryCache!.add(Map<String, dynamic>.from(tournament));
        }
        return;
      }
      await db.insert(
        'tournaments',
        {
          'id': id,
          'name': tournament['name'] as String?,
          'format': tournament['format'] as String?,
          'status': tournament['status'] as String?,
          'json_data': jsonEncode(tournament),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

  Future<void> cacheJson(String key, dynamic data) async {
    final encoded = jsonEncode(data);
    try {
      final db = await database;
      if (db == null) {
        _inMemoryKeyCache ??= {};
        _inMemoryKeyCache![key] = encoded;
        return;
      }
      await db.insert(
        'local_cache',
        {'key': key, 'json_data': encoded},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {
      _inMemoryKeyCache ??= {};
      _inMemoryKeyCache![key] = encoded;
    }
  }

  Future<dynamic> getCachedJson(String key) async {
    try {
      final db = await database;
      if (db == null) {
        final val = _inMemoryKeyCache?[key];
        return val != null ? jsonDecode(val) : null;
      }
      final results = await db.query(
        'local_cache',
        where: 'key = ?',
        whereArgs: [key],
      );
      if (results.isEmpty) {
        final val = _inMemoryKeyCache?[key];
        return val != null ? jsonDecode(val) : null;
      }
      final jsonString = results.first['json_data'] as String;
      return jsonDecode(jsonString);
    } catch (_) {
      final val = _inMemoryKeyCache?[key];
      return val != null ? jsonDecode(val) : null;
    }
  }

  Future<void> clearCache() async {
    _inMemoryCache = null;
    _inMemoryKeyCache = null;
    try {
      final db = await database;
      if (db != null) {
        await db.delete('tournaments');
        await db.delete('local_cache');
      }
    } catch (_) {}
  }
}
