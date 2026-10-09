import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'models.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
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

  Future<UserAccount?> restoreSession() async {
    final token = await _storage.read(key: _tokenKey);
    if (token == null) return null;
    try {
      final response = await _send('GET', '/me', token: token);
      return UserAccount.fromJson(response);
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        await _storage.delete(key: _tokenKey);
        return null;
      }
      rethrow;
    }
  }

  Future<UserAccount> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final response = await _send(
      'POST',
      '/auth/register',
      body: {'username': username, 'email': email, 'password': password},
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

  Future<void> logout() => _storage.delete(key: _tokenKey);

  Future<void> _saveSession(Map<String, dynamic> response) async {
    final token = response['token'];
    if (token is! String || token.isEmpty) {
      throw const ApiException('The server returned an invalid session.');
    }
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<Map<String, dynamic>> _authenticated(
    String method,
    String path, {
    Map<String, Object?>? body,
  }) async {
    final token = await _storage.read(key: _tokenKey);
    if (token == null) {
      throw const ApiException('Your session has expired. Please sign in.');
    }
    return _send(method, path, body: body, token: token);
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
      );
    }
    return decoded;
  }
}
