import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'models.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;

  /// Machine-readable reason sent by the API for some failures.
  final String? code;

  @override
  String toString() => message;
}

/// An account that is signed in on this phone, so the player can switch to it
/// without typing the password again.
class SavedAccount {
  const SavedAccount({
    required this.id,
    required this.username,
    required this.email,
  });

  final int id;
  final String username;
  final String email;
}

class ApiClient {
  ApiClient({
    http.Client? client,
    FlutterSecureStorage? storage,
    String? baseUrl,
  }) : _client = client ?? http.Client(),
       _storage = storage ?? const FlutterSecureStorage(),
       _baseUrl =
           baseUrl ??
           const String.fromEnvironment(
             'API_BASE_URL',
             defaultValue: 'http://10.0.2.2:8080',
           );

  static const _tokenKey = 'auth_token';
  final http.Client _client;
  final FlutterSecureStorage _storage;
  final String _baseUrl;

  String get baseUrl => _baseUrl;
  String get wsBaseUrl =>
      _baseUrl.replaceFirst('http://', 'ws://').replaceFirst('https://', 'wss://');

  Future<UserAccount?> restoreSession() async {
    final token = await _storage.read(key: _tokenKey);
    if (token == null) return null;
    try {
      final response = await _send('GET', '/me', token: token);
      return UserAccount.fromJson(response);
    } on ApiException catch (error) {
      // An expired token, or one for an account that no longer exists (for
      // example after the database was reseeded), cannot be retried: sign in
      // again instead.
      if (error.statusCode == 401 || error.statusCode == 404) {
        await _storage.delete(key: _tokenKey);
        await _forgetToken(token);
        return null;
      }
      rethrow;
    }
  }

  // ---- Accounts signed in on this phone ---------------------------------

  static const _accountsKey = 'accounts';

  Future<Map<String, Map<String, dynamic>>> _vault() async {
    try {
      final raw = await _storage.read(key: _accountsKey);
      if (raw == null) return {};
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final entry in decoded.entries)
          entry.key: Map<String, dynamic>.from(entry.value as Map),
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveVault(Map<String, Map<String, dynamic>> vault) =>
      _storage.write(key: _accountsKey, value: jsonEncode(vault));

  Future<void> _remember(UserAccount user, String token) async {
    try {
      final vault = await _vault();
      vault['${user.id}'] = {
        'token': token,
        'username': user.username,
        'email': user.email,
      };
      await _saveVault(vault);
    } catch (_) {}
  }

  Future<void> _forgetToken(String token) async {
    try {
      final vault = await _vault();
      final before = vault.length;
      vault.removeWhere((_, entry) => entry['token'] == token);
      if (vault.length != before) await _saveVault(vault);
    } catch (_) {}
  }

  /// Accounts signed in on this phone, A to Z.
  Future<List<SavedAccount>> savedAccounts() async {
    final vault = await _vault();
    final accounts = [
      for (final entry in vault.entries)
        if (int.tryParse(entry.key) != null)
          SavedAccount(
            id: int.parse(entry.key),
            username: '${entry.value['username']}',
            email: '${entry.value['email']}',
          ),
    ]..sort((a, b) => a.username.compareTo(b.username));
    return accounts;
  }

  /// Makes a saved account the active one. Returns null when its session is
  /// no longer valid (it is then forgotten).
  Future<UserAccount?> switchTo(int id) async {
    final entry = (await _vault())['$id'];
    final token = entry?['token'];
    if (token is! String) return null;
    await _storage.write(key: _tokenKey, value: token);
    return restoreSession();
  }

  /// Signs a saved account out of this phone without touching the active one.
  Future<void> forgetAccount(int id) async {
    final vault = await _vault();
    if (vault.remove('$id') != null) await _saveVault(vault);
  }

  /// Saves the username the player picked after signing up.
  Future<UserAccount> setUsername(String username) async {
    final response = await _authenticated(
      'PUT',
      '/me/username',
      body: {'username': username},
    );
    final user = UserAccount.fromJson(response);
    final token = await _storage.read(key: _tokenKey);
    if (token != null) await _remember(user, token);
    return user;
  }

  /// Without a [username] the player picks one right after signing up.
  Future<UserAccount> register({
    String? username,
    required String email,
    required String password,
  }) async {
    final response = await _send(
      'POST',
      '/auth/register',
      body: {
        'username': ?username,
        'email': email,
        'password': password,
      },
    );
    await _saveSession(response);
    return UserAccount.fromJson(response['user'] as Map<String, dynamic>);
  }

  Future<UserAccount> login({
    required String email,
    required String password,
  }) async {
    final response = await _send(
      'POST',
      '/auth/login',
      body: {'email': email, 'password': password},
    );
    await _saveSession(response);
    return UserAccount.fromJson(response['user'] as Map<String, dynamic>);
  }

  /// Signs in with a Google ID token; creates the account the first time.
  Future<UserAccount> loginWithGoogle(String idToken) async {
    final response = await _send(
      'POST',
      '/auth/google',
      body: {'idToken': idToken},
    );
    await _saveSession(response);
    return UserAccount.fromJson(response['user'] as Map<String, dynamic>);
  }

  Future<List<Friend>> getFriends() async {
    final response = await _authenticated('GET', '/friends');
    return (response['friends'] as List<dynamic>)
        .map((item) => Friend.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<FriendRequest>> getFriendRequests() async {
    final response = await _authenticated('GET', '/friend-requests');
    return (response['requests'] as List<dynamic>)
        .map((item) => FriendRequest.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<GamificationProfile> getGamificationProfile() async {
    final response = await _authenticated('GET', '/gamification');
    return GamificationProfile.fromJson(response);
  }

  Future<void> sendFriendRequest(String username) async {
    await _authenticated(
      'POST',
      '/friend-requests',
      body: {'username': username},
    );
  }

  Future<void> acceptFriendRequest(int requestId) async {
    await _authenticated('POST', '/friend-requests/$requestId/accept');
  }

  Future<void> removeFriend(int friendId) async {
    await _authenticated('DELETE', '/friends/$friendId');
  }

  Future<List<ChatMessage>> getMessages(int friendId, {int after = 0}) async {
    final response = await _authenticated(
      'GET',
      '/friends/$friendId/messages?after=$after',
    );
    return (response['messages'] as List<dynamic>)
        .map((item) => ChatMessage.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<ChatMessage> sendMessage(int friendId, String body) async {
    final response = await _authenticated(
      'POST',
      '/friends/$friendId/messages',
      body: {'body': body},
    );
    return ChatMessage.fromJson(response['message'] as Map<String, dynamic>);
  }

  /// Signs the active account out of this phone.
  Future<void> logout() async {
    final token = await _storage.read(key: _tokenKey);
    await _storage.delete(key: _tokenKey);
    if (token != null) await _forgetToken(token);
  }

  /// Sends a bearer-authenticated request for feature services (for example
  /// `TournamentService`) that keep their own endpoint paths and parsing.
  Future<Map<String, dynamic>> sendAuthenticated(
    String method,
    String path, {
    Map<String, Object?>? body,
  }) => _authenticated(method, path, body: body);

  Future<void> _saveSession(Map<String, dynamic> response) async {
    final token = response['token'];
    if (token is! String || token.isEmpty) {
      throw const ApiException('The server returned an invalid session.');
    }
    await _storage.write(key: _tokenKey, value: token);
    final user = response['user'];
    if (user is Map<String, dynamic>) {
      await _remember(UserAccount.fromJson(user), token);
    }
  }

  /// Called once when the server refuses the saved session (or there is none),
  /// so the app can send the player back to the login.
  void Function()? onSessionExpired;

  Future<Map<String, dynamic>> _authenticated(
    String method,
    String path, {
    Map<String, Object?>? body,
  }) async {
    final token = await _storage.read(key: _tokenKey);
    if (token == null) {
      onSessionExpired?.call();
      throw const ApiException('Your session has expired. Please sign in.');
    }
    try {
      return await _send(method, path, body: body, token: token);
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        await _storage.delete(key: _tokenKey);
        await _forgetToken(token);
        onSessionExpired?.call();
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, Object?>? body,
    String? token,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final headers = <String, String>{'accept': 'application/json'};
    if (body != null) headers['content-type'] = 'application/json';
    if (token != null) headers['authorization'] = 'Bearer $token';

    final request = http.Request(method, uri)..headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);
    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 204) return {};

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw ApiException(
        'The server returned an invalid response (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        decoded['error'] as String? ?? 'Request failed.',
        statusCode: response.statusCode,
        code: decoded['code'] as String?,
      );
    }
    return decoded;
  }
}
