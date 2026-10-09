import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

class AppDatabase {
  AppDatabase(String path) {
    File(path).parent.createSync(recursive: true);
    db = sqlite3.open(path);
    db.execute('PRAGMA foreign_keys = ON');
    db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL COLLATE NOCASE UNIQUE,
        email TEXT NOT NULL COLLATE NOCASE UNIQUE,
        password_hash TEXT NOT NULL,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS friendships (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        requester_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        addressee_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        status TEXT NOT NULL CHECK (status IN ('pending', 'accepted')),
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        CHECK (requester_id != addressee_id),
        UNIQUE (requester_id, addressee_id)
      )
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sender_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        recipient_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        body TEXT NOT NULL,
        sent_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        CHECK (sender_id != recipient_id)
      )
    ''');
    db.execute('''
      CREATE INDEX IF NOT EXISTS messages_conversation_idx
      ON messages(sender_id, recipient_id, id)
    ''');
  }

  late final Database db;

  void close() => db.close();
}
