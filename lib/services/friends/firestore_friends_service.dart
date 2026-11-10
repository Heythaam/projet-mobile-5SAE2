import 'package:cloud_firestore/cloud_firestore.dart';

import '../auth/account_service.dart';
import '../../bd/doc_store.dart';
import '../../bd/local_database.dart';
import '../../entities/user/models.dart';
import 'friends_service.dart';

typedef DocStoreOpener = Future<DocStore> Function();

/// Friends and chat in Firestore, with a copy on the phone in SQFlite.
///
/// `friendRequests/{from}_{to}`, `friendships/{pair}` and
/// `chats/{pair}/messages/{id}`. Lists and chats are read from the cloud and
/// saved on the phone; offline they come from the phone copy. Changes need a
/// connection.
class FirestoreFriendsService implements FriendsService {
  FirestoreFriendsService({
    required this.me,
    FirebaseFirestore? db,
    DocStoreOpener? openStore,
  }) : _db = db ?? FirebaseFirestore.instance,
       _openStore = openStore ?? _openDefault;

  final UserAccount me;
  final FirebaseFirestore _db;
  final DocStoreOpener _openStore;

  static Future<DocStore> _openDefault() async =>
      DocStore(await LocalDatabase.open());

  String get _uid => me.storageUid;
  String get _friendsKey => '$_uid/friends';
  String get _requestsKey => '$_uid/friend_requests';

  static const _offline = FriendsException(
    'No connection. Check your internet and try again.',
  );

  Friend _friend(String uid, String username) =>
      Friend(id: stableUserId(uid), uid: uid, username: username);

  FriendRequest _request(String from, String name, int createdAtMs) =>
      FriendRequest(
        id: stableUserId('${from}_$_uid'),
        user: _friend(from, name),
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          createdAtMs,
        ).toIso8601String(),
      );

  @override
  Future<List<Friend>> getFriends() async {
    final store = await _openStore();
    try {
      final snap = await _db
          .collection('friendships')
          .where('uids', arrayContains: _uid)
          .get();
      final rows = <String, Map<String, Object?>>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        final uids = (data['uids'] as List).cast<String>();
        final other = uids.firstWhere((u) => u != _uid, orElse: () => '');
        if (other.isEmpty) continue;
        final names = Map<String, dynamic>.from(data['names'] as Map);
        rows[other] = {'uid': other, 'username': '${names[other] ?? other}'};
      }
      await store.replaceAll(_friendsKey, rows);
      return _sorted([
        for (final r in rows.values) _friend('${r['uid']}', '${r['username']}'),
      ]);
    } on FirebaseException {
      return _sorted([
        for (final r in await store.list(_friendsKey))
          _friend('${r['uid']}', '${r['username']}'),
      ]);
    }
  }

  static List<Friend> _sorted(List<Friend> friends) =>
      friends..sort((a, b) => a.username.compareTo(b.username));

  @override
  Future<List<FriendRequest>> getFriendRequests() async {
    final store = await _openStore();
    try {
      final snap = await _db
          .collection('friendRequests')
          .where('toUid', isEqualTo: _uid)
          .get();
      final rows = <String, Map<String, Object?>>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        rows['${data['fromUid']}'] = {
          'uid': data['fromUid'],
          'username': data['fromName'],
          'createdAtMs': (data['createdAtMs'] as num?)?.toInt() ?? 0,
        };
      }
      await store.replaceAll(_requestsKey, rows);
      return _requests(rows.values);
    } on FirebaseException {
      return _requests(await store.list(_requestsKey));
    }
  }

  List<FriendRequest> _requests(Iterable<Map<String, Object?>> rows) => [
    for (final r in rows)
      _request(
        '${r['uid']}',
        '${r['username']}',
        (r['createdAtMs'] as num?)?.toInt() ?? 0,
      ),
  ];

  @override
  Future<void> sendFriendRequest(String username) async {
    final name = username.trim().toLowerCase();
    if (name == me.username.toLowerCase()) {
      throw const FriendsException('That is you.');
    }
    try {
      final claim = await _db.collection('usernames').doc(name).get();
      final other = claim.data()?['uid'];
      if (other is! String) {
        throw FriendsException('No player is called @$name.');
      }
      final pair = pairId(_uid, other);
      if ((await _db.collection('friendships').doc(pair).get()).exists) {
        throw const FriendsException('You are already friends.');
      }
      final theirs = await _db
          .collection('friendRequests')
          .doc('${other}_$_uid')
          .get();
      if (theirs.exists) {
        // They already asked you: accept instead of asking again.
        await _makeFriends(other, '${theirs.data()?['fromName'] ?? name}');
        return;
      }
      await _db.collection('friendRequests').doc('${_uid}_$other').set({
        'fromUid': _uid,
        'fromName': me.username,
        'toUid': other,
        'toName': name,
        'createdAtMs': DateTime.now().millisecondsSinceEpoch,
      });
    } on FirebaseException {
      throw _offline;
    }
  }

  @override
  Future<void> acceptFriendRequest(FriendRequest request) async {
    final other = request.user.uid;
    if (other == null) {
      throw const FriendsException('That request is not valid.');
    }
    try {
      await _makeFriends(other, request.user.username);
    } on FirebaseException {
      throw _offline;
    }
  }

  Future<void> _makeFriends(String other, String otherName) async {
    final batch = _db.batch();
    batch.set(_db.collection('friendships').doc(pairId(_uid, other)), {
      'uids': [_uid, other],
      'names': {_uid: me.username, other: otherName},
      'createdAtMs': DateTime.now().millisecondsSinceEpoch,
    });
    batch.delete(_db.collection('friendRequests').doc('${other}_$_uid'));
    batch.delete(_db.collection('friendRequests').doc('${_uid}_$other'));
    await batch.commit();
  }

  @override
  Future<void> removeFriend(Friend friend) async {
    final other = friend.uid;
    if (other == null) return;
    try {
      await _db.collection('friendships').doc(pairId(_uid, other)).delete();
    } on FirebaseException {
      throw _offline;
    }
  }

  CollectionReference<Map<String, dynamic>> _messages(String other) =>
      _db.collection('chats').doc(pairId(_uid, other)).collection('messages');

  String _chatKey(String other) => '$_uid/chat/${pairId(_uid, other)}';

  ChatMessage _message(Map<String, Object?> data) => ChatMessage(
    id: (data['sentAtMs'] as num).toInt(),
    senderId: stableUserId('${data['from']}'),
    body: '${data['body']}',
    sentAt: DateTime.fromMillisecondsSinceEpoch(
      (data['sentAtMs'] as num).toInt(),
    ).toIso8601String(),
  );

  @override
  Future<List<ChatMessage>> getMessages(Friend friend, {int after = 0}) async {
    final other = friend.uid;
    if (other == null) return const [];
    final store = await _openStore();
    try {
      final snap = await _messages(other)
          .where('sentAtMs', isGreaterThan: after)
          .orderBy('sentAtMs')
          .get();
      final messages = <ChatMessage>[];
      for (final doc in snap.docs) {
        final data = doc.data();
        await store.put(_chatKey(other), doc.id, data);
        messages.add(_message(data));
      }
      return messages;
    } on FirebaseException {
      final cached = [
        for (final data in await store.list(_chatKey(other))) _message(data),
      ].where((m) => m.id > after).toList()
        ..sort((a, b) => a.id.compareTo(b.id));
      return cached;
    }
  }

  @override
  Future<ChatMessage> sendMessage(Friend friend, String body) async {
    final other = friend.uid;
    if (other == null) {
      throw const FriendsException('That friend is not valid.');
    }
    final data = {
      'from': _uid,
      'body': body,
      'sentAtMs': DateTime.now().millisecondsSinceEpoch,
    };
    try {
      final ref = await _messages(other).add(data);
      await (await _openStore()).put(_chatKey(other), ref.id, data);
      return _message(data);
    } on FirebaseException {
      throw _offline;
    }
  }
}
