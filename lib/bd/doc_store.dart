import 'dart:convert';

import 'package:sqflite/sqflite.dart';

/// Small JSON documents kept on the phone with SQFlite, grouped in
/// collections. Modules keep a phone copy of what they read from Firestore
/// here, so lists and chats still open without a connection.
class DocStore {
  DocStore(this._db);

  final Database _db;

  Future<void> put(
    String collection,
    String id,
    Map<String, Object?> json,
  ) => _db.insert('docs', {
    'collection': collection,
    'id': id,
    'json': jsonEncode(json),
    'updated_at': DateTime.now().millisecondsSinceEpoch,
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  /// Makes the collection hold exactly [rows] (id to document).
  Future<void> replaceAll(
    String collection,
    Map<String, Map<String, Object?>> rows,
  ) => _db.transaction((txn) async {
    await txn.delete('docs', where: 'collection = ?', whereArgs: [collection]);
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final entry in rows.entries) {
      await txn.insert('docs', {
        'collection': collection,
        'id': entry.key,
        'json': jsonEncode(entry.value),
        'updated_at': now,
      });
    }
  });

  Future<Map<String, Object?>?> get(String collection, String id) async {
    final rows = await _db.query(
      'docs',
      where: 'collection = ? AND id = ?',
      whereArgs: [collection, id],
      limit: 1,
    );
    return rows.isEmpty ? null : _decode(rows.first);
  }

  /// Every document of the collection, in id order.
  Future<List<Map<String, Object?>>> list(String collection) async {
    final rows = await _db.query(
      'docs',
      where: 'collection = ?',
      whereArgs: [collection],
      orderBy: 'id ASC',
    );
    return [for (final row in rows) _decode(row)];
  }

  Future<void> remove(String collection, String id) => _db.delete(
    'docs',
    where: 'collection = ? AND id = ?',
    whereArgs: [collection, id],
  );

  static Map<String, Object?> _decode(Map<String, Object?> row) =>
      Map<String, Object?>.from(
        jsonDecode(row['json']! as String) as Map<String, dynamic>,
      );
}
