import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:football_match_app/services/api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ApiClient client(int status, Map<String, Object?> body) => ApiClient(
    baseUrl: 'http://api.test',
    client: MockClient((_) async => http.Response(jsonEncode(body), status)),
  );

  for (final (status, reason) in [
    (401, 'Your session has expired. Please sign in again.'),
    (404, 'Account not found.'),
  ]) {
    test(
      'a $status on session restore clears the token and signs out',
      () async {
        FlutterSecureStorage.setMockInitialValues({'auth_token': 'old'});
        final api = client(status, {'error': reason});

        expect(await api.restoreSession(), isNull);
        expect(await const FlutterSecureStorage().readAll(), isEmpty);
      },
    );
  }

  test('google sign-in posts the ID token and stores the session', () async {
    FlutterSecureStorage.setMockInitialValues({});
    String? sentBody;
    final api = ApiClient(
      baseUrl: 'http://api.test',
      client: MockClient((request) async {
        expect(request.url.path, '/auth/google');
        sentBody = request.body;
        return http.Response(
          jsonEncode({
            'token': 'jwt',
            'user': {
              'id': 7,
              'username': 'player_abc123',
              'email': 'fan@example.com',
              'usernameChosen': false,
            },
          }),
          201,
        );
      }),
    );

    final user = await api.loginWithGoogle('google-token');

    expect(jsonDecode(sentBody!), {'idToken': 'google-token'});
    expect(user.usernameChosen, isFalse);
    expect(await const FlutterSecureStorage().read(key: 'auth_token'), 'jwt');
  });

  test('other failures keep the token so the app can retry', () async {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'kept'});
    final api = client(500, {'error': 'Server error.'});

    await expectLater(api.restoreSession(), throwsA(isA<ApiException>()));
    expect(await const FlutterSecureStorage().readAll(), isNotEmpty);
  });

  test('a 401 on a request clears the token and tells the app', () async {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'old'});
    final api = client(401, {'error': 'Invalid session.'});
    var expired = 0;
    api.onSessionExpired = () => expired++;

    await expectLater(api.getFriends(), throwsA(isA<ApiException>()));
    expect(expired, 1);
    expect(await const FlutterSecureStorage().readAll(), isEmpty);
  });

  test('a request without a saved session tells the app', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final api = client(200, {});
    var expired = 0;
    api.onSessionExpired = () => expired++;

    await expectLater(api.getFriends(), throwsA(isA<ApiException>()));
    expect(expired, 1);
  });

  test('signed-in accounts are kept so the player can switch', () async {
    FlutterSecureStorage.setMockInitialValues({});
    String name(int id) => id == 1 ? 'ann' : 'bob';
    final api = ApiClient(
      baseUrl: 'http://api.test',
      client: MockClient((request) async {
        if (request.url.path == '/auth/login') {
          final email = (jsonDecode(request.body) as Map)['email'] as String;
          final id = email == 'a@x.tn' ? 1 : 2;
          return http.Response(
            jsonEncode({
              'token': 'tok$id',
              'user': {'id': id, 'username': name(id), 'email': email},
            }),
            200,
          );
        }
        if (request.url.path == '/me') {
          final id = request.headers['authorization'] == 'Bearer tok1' ? 1 : 2;
          return http.Response(
            jsonEncode({
              'id': id,
              'username': name(id),
              'email': id == 1 ? 'a@x.tn' : 'b@x.tn',
            }),
            200,
          );
        }
        return http.Response('{}', 200);
      }),
    );

    await api.login(email: 'a@x.tn', password: 'x');
    await api.login(email: 'b@x.tn', password: 'x');
    expect((await api.savedAccounts()).map((a) => a.username), ['ann', 'bob']);

    final back = await api.switchTo(1);
    expect(back?.username, 'ann');

    await api.forgetAccount(2);
    expect((await api.savedAccounts()).map((a) => a.id), [1]);

    await api.logout();
    expect(await api.savedAccounts(), isEmpty);
  });
}
