import 'dart:math' as math;

import 'package:sqflite/sqflite.dart';

enum LocalMatchError {
  invalidHost,
  invalidStadium,
  invalidCapacity,
  invalidTime,
  codeUnavailable,
  notFound,
  full,
  alreadyJoined,
  notPlayer,
  hostCannotLeave,
  notHost,
  started,
}

class LocalMatchException implements Exception {
  const LocalMatchException(this.error, this.message);

  final LocalMatchError error;
  final String message;

  @override
  String toString() => message;
}

/// A match saved on the phone. [slots] has one entry per place: the player's
/// uid, or null when the place is free. The host always starts in slot 0.
class LocalMatch {
  const LocalMatch({
    required this.code,
    required this.hostUid,
    required this.stadium,
    required this.scheduledAt,
    required this.capacity,
    required this.isPublic,
    required this.slots,
    required this.slotNames,
    required this.createdAt,
    required this.updatedAt,
  });

  final String code;
  final String hostUid;
  final String stadium;
  final DateTime scheduledAt;
  final int capacity;
  final bool isPublic;
  final List<String?> slots;

  /// Display name of the player in each slot, same order as [slots]. Empty
  /// when the name was not given.
  final List<String?> slotNames;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get players => slots.where((uid) => uid != null).length;
  bool get isFull => players >= capacity;
  bool hasPlayer(String uid) => slots.contains(uid);
}

DateTime _fromMs(int ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);

/// CRUD for matches and their players, on the phone's SQFlite database.
class MatchLocalStore {
  MatchLocalStore(this._db, {DateTime Function()? clock, math.Random? random})
    : _clock = clock ?? DateTime.now,
      _random = random ?? math.Random();

  final Database _db;
  final DateTime Function() _clock;
  final math.Random _random;

  /// No 0, 1, I or L, so a code read aloud is hard to mix up.
  static const codeAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  static const codeLength = 5;
  static const minCapacity = 2;
  static const maxCapacity = 30;
  static const stadiumMaxLength = 60;

  static final _codePattern = RegExp(r'^[A-Z0-9]{5}$');

  // ---- Create -----------------------------------------------------------

  /// Saves a new match with the host in slot 0 and returns it with its code.
  Future<LocalMatch> create({
    required String hostUid,
    required String stadium,
    required DateTime scheduledAt,
    required int capacity,
    bool isPublic = false,
    String hostName = '',
  }) async {
    if (hostUid.trim().isEmpty) {
      throw const LocalMatchException(
        LocalMatchError.invalidHost,
        'A host is required.',
      );
    }
    final place = stadium.trim();
    if (place.isEmpty || place.length > stadiumMaxLength) {
      throw const LocalMatchException(
        LocalMatchError.invalidStadium,
        'Pick a stadium.',
      );
    }
    if (capacity < minCapacity || capacity > maxCapacity) {
      throw const LocalMatchException(
        LocalMatchError.invalidCapacity,
        'A match needs between 2 and 30 players.',
      );
    }
    final now = _clock();
    if (scheduledAt.millisecondsSinceEpoch <= now.millisecondsSinceEpoch) {
      throw const LocalMatchException(
        LocalMatchError.invalidTime,
        'Pick a time in the future.',
      );
    }

    return _db.transaction((txn) async {
      String? code;
      for (var attempt = 0; attempt < 20 && code == null; attempt++) {
        final candidate = _randomCode();
        if (await _load(txn, candidate) == null) code = candidate;
      }
      if (code == null) {
        throw const LocalMatchException(
          LocalMatchError.codeUnavailable,
          'Could not make a match code. Try again.',
        );
      }
      final ms = now.millisecondsSinceEpoch;
      await txn.insert('matches', {
        'code': code,
        'host_uid': hostUid,
        'stadium': place,
        'scheduled_at': scheduledAt.millisecondsSinceEpoch,
        'capacity': capacity,
        'is_public': isPublic ? 1 : 0,
        'created_at': ms,
        'updated_at': ms,
      });
      await txn.insert('match_players', {
        'match_code': code,
        'uid': hostUid,
        'slot': 0,
        'display_name': hostName.trim(),
        'joined_at': ms,
      });
      return (await _load(txn, code))!;
    });
  }

  // ---- Read -------------------------------------------------------------

  /// Looks a match up by its code, ignoring case and spaces.
  Future<LocalMatch?> getByCode(String code) => _load(_db, code);

  /// Public matches that have not started, soonest first.
  Future<List<LocalMatch>> publicUpcoming() async {
    final rows = await _db.query(
      'matches',
      columns: ['code'],
      where: 'is_public = 1 AND scheduled_at > ?',
      whereArgs: [_clock().millisecondsSinceEpoch],
      orderBy: 'scheduled_at ASC',
    );
    return _loadAll(_db, rows);
  }

  /// Every match that has not started, soonest first.
  Future<List<LocalMatch>> allUpcoming() async {
    final rows = await _db.query(
      'matches',
      columns: ['code'],
      where: 'scheduled_at > ?',
      whereArgs: [_clock().millisecondsSinceEpoch],
      orderBy: 'scheduled_at ASC',
    );
    return _loadAll(_db, rows);
  }

  /// The next match [uid] plays in that has not started, or null.
  Future<LocalMatch?> upcomingFor(String uid) async {
    final rows = await _db.rawQuery(
      'SELECT m.code FROM matches m '
      'JOIN match_players p ON p.match_code = m.code '
      'WHERE p.uid = ? AND m.scheduled_at > ? '
      'ORDER BY m.scheduled_at ASC LIMIT 1',
      [uid, _clock().millisecondsSinceEpoch],
    );
    if (rows.isEmpty) return null;
    return _load(_db, rows.first['code']! as String);
  }

  // ---- Update -----------------------------------------------------------

  /// Puts [uid] in the lowest free slot. [name] is shown in the lobby.
  Future<LocalMatch> join(String code, String uid, {String name = ''}) {
    return _db.transaction((txn) async {
      final match = await _requireOpen(txn, code);
      if (match.hasPlayer(uid)) {
        throw const LocalMatchException(
          LocalMatchError.alreadyJoined,
          'You are already in this match.',
        );
      }
      final free = match.slots.indexOf(null);
      if (free < 0) {
        throw const LocalMatchException(
          LocalMatchError.full,
          'This match is full.',
        );
      }
      final ms = _clock().millisecondsSinceEpoch;
      await txn.insert('match_players', {
        'match_code': match.code,
        'uid': uid,
        'slot': free,
        'display_name': name.trim(),
        'joined_at': ms,
      });
      await _touch(txn, match);
      return (await _load(txn, match.code))!;
    });
  }

  /// Frees [uid]'s slot. The host cannot leave; they cancel instead.
  Future<LocalMatch> leave(String code, String uid) {
    return _db.transaction((txn) async {
      final match = await _requireOpen(txn, code);
      if (!match.hasPlayer(uid)) {
        throw const LocalMatchException(
          LocalMatchError.notPlayer,
          'You are not in this match.',
        );
      }
      if (uid == match.hostUid) {
        throw const LocalMatchException(
          LocalMatchError.hostCannotLeave,
          'The host cancels the match instead of leaving.',
        );
      }
      await txn.delete(
        'match_players',
        where: 'match_code = ? AND uid = ?',
        whereArgs: [match.code, uid],
      );
      await _touch(txn, match);
      return (await _load(txn, match.code))!;
    });
  }

  // ---- Delete -----------------------------------------------------------

  /// Removes the match and all its players. Only the host can do this.
  Future<void> cancel(String code, String uid) {
    return _db.transaction((txn) async {
      final match = await _load(txn, code);
      if (match == null) throw _notFound();
      if (match.hostUid != uid) {
        throw const LocalMatchException(
          LocalMatchError.notHost,
          'Only the host can cancel this match.',
        );
      }
      await txn.delete('matches', where: 'code = ?', whereArgs: [match.code]);
    });
  }

  // ---- Helpers ----------------------------------------------------------

  String _randomCode() => List.generate(
    codeLength,
    (_) => codeAlphabet[_random.nextInt(codeAlphabet.length)],
  ).join();

  LocalMatchException _notFound() => const LocalMatchException(
    LocalMatchError.notFound,
    'No match with that code.',
  );

  Future<LocalMatch> _requireOpen(DatabaseExecutor executor, String code) async {
    final match = await _load(executor, code);
    if (match == null) throw _notFound();
    if (match.scheduledAt.millisecondsSinceEpoch <=
        _clock().millisecondsSinceEpoch) {
      throw const LocalMatchException(
        LocalMatchError.started,
        'This match has already started.',
      );
    }
    return match;
  }

  Future<void> _touch(DatabaseExecutor executor, LocalMatch match) async {
    final ms = math.max(
      _clock().millisecondsSinceEpoch,
      match.updatedAt.millisecondsSinceEpoch + 1,
    );
    await executor.update(
      'matches',
      {'updated_at': ms},
      where: 'code = ?',
      whereArgs: [match.code],
    );
  }

  Future<List<LocalMatch>> _loadAll(
    DatabaseExecutor executor,
    List<Map<String, Object?>> rows,
  ) async {
    final matches = <LocalMatch>[];
    for (final row in rows) {
      final match = await _load(executor, row['code']! as String);
      if (match != null) matches.add(match);
    }
    return matches;
  }

  Future<LocalMatch?> _load(DatabaseExecutor executor, String code) async {
    final normalized = code.trim().toUpperCase();
    if (!_codePattern.hasMatch(normalized)) return null;
    final rows = await executor.query(
      'matches',
      where: 'code = ?',
      whereArgs: [normalized],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    final capacity = row['capacity']! as int;
    final players = await executor.query(
      'match_players',
      where: 'match_code = ?',
      whereArgs: [normalized],
      orderBy: 'slot ASC',
    );
    final slots = List<String?>.filled(capacity, null);
    final names = List<String?>.filled(capacity, null);
    for (final player in players) {
      final slot = player['slot']! as int;
      if (slot < 0 || slot >= capacity) continue;
      slots[slot] = player['uid']! as String;
      names[slot] = player['display_name']! as String;
    }
    return LocalMatch(
      code: row['code']! as String,
      hostUid: row['host_uid']! as String,
      stadium: row['stadium']! as String,
      scheduledAt: _fromMs(row['scheduled_at']! as int),
      capacity: capacity,
      isPublic: (row['is_public']! as int) == 1,
      slots: slots,
      slotNames: names,
      createdAt: _fromMs(row['created_at']! as int),
      updatedAt: _fromMs(row['updated_at']! as int),
    );
  }
}
