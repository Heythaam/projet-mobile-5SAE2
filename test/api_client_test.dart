import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:football_match_app/api_client.dart';
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

  test('other failures keep the token so the app can retry', () async {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'kept'});
    final api = client(500, {'error': 'Server error.'});

    await expectLater(api.restoreSession(), throwsA(isA<ApiException>()));
    expect(await const FlutterSecureStorage().readAll(), isNotEmpty);
  });
}
