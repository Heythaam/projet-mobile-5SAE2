import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../entities/user/models.dart';
import 'account_service.dart';
import 'google_auth.dart';

/// Firebase Auth for the login and Firestore for the username.
///
/// `users/{uid}` holds the profile and `usernames/{name}` points to the uid
/// that owns that username, so two players can never share one.
class FirebaseAccountService implements AccountService {
  FirebaseAccountService({
    required this.google,
    FirebaseAuth? auth,
    FirebaseFirestore? db,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _db = db ?? FirebaseFirestore.instance;

  final GoogleAuth google;
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  static const _rememberedKey = 'remembered_accounts';

  @override
  bool get supportsGoogle => true;

  @override
  Future<UserAccount?> restoreSession() async {
    final user = await _auth.authStateChanges().first;
    if (user == null) return null;
    return _account(user);
  }

  @override
  Future<UserAccount> register({
    required String email,
    required String password,
  }) async {
    final credential = await _run(
      () => _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      ),
    );
    return _account(credential.user!);
  }

  @override
  Future<UserAccount> login({
    required String email,
    required String password,
  }) async {
    final credential = await _run(
      () => _auth.signInWithEmailAndPassword(email: email, password: password),
    );
    return _account(credential.user!);
  }

  @override
  Future<UserAccount?> loginWithGoogle() async {
    final idToken = await google.idToken();
    if (idToken == null) return null;
    final credential = await _run(
      () => _auth.signInWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      ),
    );
    return _account(credential.user!);
  }

  @override
  Future<UserAccount> setUsername(String username) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AccountException('Please sign in again.');
    }
    final name = username.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(name)) {
      throw const AccountException(
        'Use 3 to 20 letters, numbers or underscores.',
      );
    }
    final claim = _db.collection('usernames').doc(name);
    final profile = _db.collection('users').doc(user.uid);
    try {
      await _db.runTransaction((tx) async {
        final owner = await tx.get(claim);
        if (owner.exists && owner.data()?['uid'] != user.uid) {
          throw const AccountException('That username is already taken.');
        }
        final current = (await tx.get(profile)).data();
        final oldName = current?['username'];
        tx.set(claim, {'uid': user.uid});
        if (current?['usernameChosen'] == true &&
            oldName is String &&
            oldName != name) {
          tx.delete(_db.collection('usernames').doc(oldName));
        }
        tx.set(profile, {
          'username': name,
          'usernameChosen': true,
        }, SetOptions(merge: true));
      });
    } on AccountException {
      rethrow;
    } on FirebaseException catch (error) {
      throw AccountException(_cloudMessage(error));
    }
    return _account(user);
  }

  @override
  Future<void> logout() async {
    await google.signOut();
    await _auth.signOut();
  }

  @override
  Future<List<RememberedAccount>> rememberedAccounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_rememberedKey);
      if (raw == null) return const [];
      final list = (jsonDecode(raw) as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .map(
            (e) => RememberedAccount(
              uid: '${e['uid']}',
              username: '${e['username']}',
              email: '${e['email']}',
            ),
          )
          .toList()
        ..sort((a, b) => a.username.compareTo(b.username));
      return list;
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> forget(String uid) async {
    final all = await rememberedAccounts();
    await _saveRemembered(all.where((a) => a.uid != uid));
  }

  Future<void> _saveRemembered(Iterable<RememberedAccount> accounts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _rememberedKey,
        jsonEncode([
          for (final a in accounts)
            {'uid': a.uid, 'username': a.username, 'email': a.email},
        ]),
      );
    } catch (_) {}
  }

  Future<void> _remember(UserAccount account) async {
    final all = await rememberedAccounts();
    await _saveRemembered([
      ...all.where((a) => a.uid != account.storageUid),
      RememberedAccount(
        uid: account.storageUid,
        username: account.username,
        email: account.email,
      ),
    ]);
  }

  /// Reads (or creates the first time) `users/{uid}` and turns it into the
  /// account the app works with.
  Future<UserAccount> _account(User user) async {
    final ref = _db.collection('users').doc(user.uid);
    try {
      var data = (await ref.get()).data();
      if (data == null) {
        data = {
          'uid': user.uid,
          'username': _temporaryUsername(),
          'email': user.email ?? '',
          'usernameChosen': false,
          'bio': '',
          'avatarId': 0,
        };
        await ref.set({...data, 'createdAt': FieldValue.serverTimestamp()});
      }
      final account = UserAccount(
        id: stableUserId(user.uid),
        uid: user.uid,
        username: '${data['username']}',
        email: user.email ?? '${data['email']}',
        usernameChosen: data['usernameChosen'] != false,
      );
      await _remember(account);
      return account;
    } on FirebaseException catch (error) {
      throw AccountException(_cloudMessage(error));
    }
  }

  Future<T> _run<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseAuthException catch (error) {
      throw AccountException(friendlyAuthError(error.code));
    }
  }

  static String _temporaryUsername() {
    const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return 'player_'
        '${List.generate(6, (_) => alphabet[random.nextInt(36)]).join()}';
  }

  static String _cloudMessage(FirebaseException error) =>
      error.code == 'unavailable'
      ? 'No connection. Check your internet and try again.'
      : 'Could not reach the cloud: ${error.message ?? error.code}';
}

/// Plain words for a Firebase Auth error code.
String friendlyAuthError(String code) => switch (code) {
  'email-already-in-use' => 'That email is already registered.',
  'invalid-email' => 'Enter a valid email address.',
  'weak-password' => 'Password must be at least 6 characters.',
  'user-not-found' ||
  'wrong-password' ||
  'invalid-credential' => 'Email or password is incorrect.',
  'user-disabled' => 'This account has been disabled.',
  'too-many-requests' => 'Too many attempts. Try again in a few minutes.',
  'network-request-failed' => 'No connection. Check your internet.',
  'account-exists-with-different-credential' =>
    'That email is registered another way. Sign in with your password.',
  _ => 'Sign-in failed ($code).',
};
