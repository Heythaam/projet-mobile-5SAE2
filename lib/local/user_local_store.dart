import 'dart:math' as math;

import 'package:sqflite/sqflite.dart';

enum LocalUserError {
  invalidUid,
  invalidUsername,
  invalidEmail,
  invalidBio,
  invalidPosition,
  invalidAvatar,
  usernameTaken,
  uidTaken,
  notFound,
}

class LocalUserException implements Exception {
  const LocalUserException(this.error, this.message);

  final LocalUserError error;
  final String message;

  @override
  String toString() => message;
}

/// The signed-in user's profile as stored on the phone. It never holds a
/// password, and never XP, level or streak.
class LocalUser {
  const LocalUser({
    required this.uid,
    required this.username,
    required this.email,
    required this.createdAt,
    required this.updatedAt,
    this.bio = '',
    this.position,
    this.avatarId = 0,
  });

  factory LocalUser.fromRow(Map<String, Object?> row) => LocalUser(
    uid: row['uid']! as String,
    username: row['username']! as String,
    email: row['email']! as String,
    bio: row['bio']! as String,
    position: row['position'] as String?,
    avatarId: row['avatar_id']! as int,
    createdAt: _fromMs(row['created_at']! as int),
    updatedAt: _fromMs(row['updated_at']! as int),
  );

  final String uid;
  final String username;
  final String email;
  final String bio;

  /// One of [UserLocalStore.positions], or null.
  final String? position;
  final int avatarId;
  final DateTime createdAt;
  final DateTime updatedAt;
}

DateTime _fromMs(int ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);

/// CRUD for the local user profile and the single signed-in session row.
class UserLocalStore {
  UserLocalStore(this._db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final Database _db;
  final DateTime Function() _clock;

  static const positions = {'GK', 'DEF', 'MID', 'FWD'};
  static const bioMaxLength = 160;

  // Same rules as the API, so a name valid here is valid there.
  static final _usernamePattern = RegExp(r'^[a-z0-9_]{3,20}$');
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  // ---- Create -----------------------------------------------------------

  /// Inserts the profile after Firebase sign-up succeeds. Usernames and emails
  /// are trimmed and lowercased.
  Future<LocalUser> create({
    required String uid,
    required String username,
    required String email,
    String bio = '',
    String? position,
    int avatarId = 0,
  }) async {
    if (uid.trim().isEmpty) {
      throw const LocalUserException(
        LocalUserError.invalidUid,
        'A user id is required.',
      );
    }
    final name = _checkUsername(username);
    final mail = _checkEmail(email);
    final about = _checkBio(bio);
    _checkPosition(position);
    _checkAvatar(avatarId);

    return _db.transaction((txn) async {
      if (await _find(txn, 'uid = ?', [uid]) != null) {
        throw const LocalUserException(
          LocalUserError.uidTaken,
          'This account is already saved on the phone.',
        );
      }
      if (await _find(txn, 'username = ?', [name]) != null) {
        throw const LocalUserException(
          LocalUserError.usernameTaken,
          'That username is taken.',
        );
      }
      final ms = _clock().millisecondsSinceEpoch;
      await txn.insert('users', {
        'uid': uid,
        'username': name,
        'email': mail,
        'bio': about,
        'position': position,
        'avatar_id': avatarId,
        'created_at': ms,
        'updated_at': ms,
      });
      return (await _find(txn, 'uid = ?', [uid]))!;
    });
  }

  // ---- Read -------------------------------------------------------------

  Future<LocalUser?> getByUid(String uid) => _find(_db, 'uid = ?', [uid]);

  Future<LocalUser?> getByUsername(String username) =>
      _find(_db, 'username = ?', [username.trim().toLowerCase()]);

  /// The user whose session row is set, or null when signed out.
  Future<LocalUser?> currentUser() async {
    final rows = await _db.rawQuery(
      'SELECT u.* FROM users u JOIN session s ON s.uid = u.uid WHERE s.id = 1',
    );
    return rows.isEmpty ? null : LocalUser.fromRow(rows.first);
  }

  // ---- Update -----------------------------------------------------------

  /// Changes only the fields that are passed. Use [clearPosition] to remove the
  /// position. `updated_at` moves forward on every real change, even when the
  /// clock does not, so "last write wins" stays reliable.
  Future<LocalUser> updateProfile(
    String uid, {
    String? username,
    String? bio,
    String? position,
    bool clearPosition = false,
    int? avatarId,
  }) async {
    assert(
      !(clearPosition && position != null),
      'Pass either position or clearPosition, not both.',
    );
    return _db.transaction((txn) async {
      final current = await _find(txn, 'uid = ?', [uid]);
      if (current == null) throw _notFound();

      final values = <String, Object?>{};
      if (username != null) {
        final name = _checkUsername(username);
        if (name != current.username) {
          if (await _find(txn, 'username = ? AND uid != ?', [name, uid]) !=
              null) {
            throw const LocalUserException(
              LocalUserError.usernameTaken,
              'That username is taken.',
            );
          }
          values['username'] = name;
        }
      }
      if (bio != null) {
        final about = _checkBio(bio);
        if (about != current.bio) values['bio'] = about;
      }
      if (position != null) {
        _checkPosition(position);
        if (position != current.position) values['position'] = position;
      }
      if (clearPosition && current.position != null) {
        values['position'] = null;
      }
      if (avatarId != null) {
        _checkAvatar(avatarId);
        if (avatarId != current.avatarId) values['avatar_id'] = avatarId;
      }

      if (values.isEmpty) return current;

      values['updated_at'] = math.max(
        _clock().millisecondsSinceEpoch,
        current.updatedAt.millisecondsSinceEpoch + 1,
      );
      await txn.update('users', values, where: 'uid = ?', whereArgs: [uid]);
      return (await _find(txn, 'uid = ?', [uid]))!;
    });
  }

  // ---- Delete -----------------------------------------------------------

  /// Removes the profile. The session row goes with it (ON DELETE CASCADE).
  /// Returns false when the user was not stored.
  Future<bool> delete(String uid) async {
    final count = await _db.delete('users', where: 'uid = ?', whereArgs: [uid]);
    return count > 0;
  }

  // ---- Session ----------------------------------------------------------

  /// Marks [uid] as the signed-in user, replacing any previous session.
  Future<void> startSession(String uid) async {
    await _db.transaction((txn) async {
      if (await _find(txn, 'uid = ?', [uid]) == null) throw _notFound();
      await txn.insert('session', {
        'id': 1,
        'uid': uid,
        'signed_in_at': _clock().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void> endSession() => _db.delete('session');

  // ---- Helpers ----------------------------------------------------------

  Future<LocalUser?> _find(
    DatabaseExecutor executor,
    String where,
    List<Object?> args,
  ) async {
    final rows = await executor.query(
      'users',
      where: where,
      whereArgs: args,
      limit: 1,
    );
    return rows.isEmpty ? null : LocalUser.fromRow(rows.first);
  }

  LocalUserException _notFound() => const LocalUserException(
    LocalUserError.notFound,
    'No saved profile for this account.',
  );

  String _checkUsername(String value) {
    final name = value.trim().toLowerCase();
    if (!_usernamePattern.hasMatch(name)) {
      throw const LocalUserException(
        LocalUserError.invalidUsername,
        'Username must be 3-20 characters (letters, numbers, or underscores).',
      );
    }
    return name;
  }

  String _checkEmail(String value) {
    final mail = value.trim().toLowerCase();
    if (!_emailPattern.hasMatch(mail) || mail.length > 254) {
      throw const LocalUserException(
        LocalUserError.invalidEmail,
        'Enter a valid email address.',
      );
    }
    return mail;
  }

  String _checkBio(String value) {
    final about = value.trim();
    if (about.length > bioMaxLength) {
      throw const LocalUserException(
        LocalUserError.invalidBio,
        'Bio must be 160 characters or fewer.',
      );
    }
    return about;
  }

  void _checkPosition(String? value) {
    if (value != null && !positions.contains(value)) {
      throw const LocalUserException(
        LocalUserError.invalidPosition,
        'Position must be GK, DEF, MID or FWD.',
      );
    }
  }

  void _checkAvatar(int value) {
    if (value < 0) {
      throw const LocalUserException(
        LocalUserError.invalidAvatar,
        'Pick a valid avatar.',
      );
    }
  }
}
