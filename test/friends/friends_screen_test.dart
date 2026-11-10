import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:football_match_app/api_client.dart';
import 'package:football_match_app/friends/friends_screen.dart';
import 'package:football_match_app/models.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <String>[];
  var accepted = false;

  ApiClient api() => ApiClient(
    baseUrl: 'http://api.test',
    client: MockClient((request) async {
      calls.add('${request.method} ${request.url.path}');
      Map<String, Object?> body;
      switch ('${request.method} ${request.url.path}') {
        case 'GET /friends':
          body = {
            'friends': [
              {'id': 2, 'username': 'samira'},
              if (accepted) {'id': 3, 'username': 'noah'},
            ],
          };
        case 'GET /friend-requests':
          body = {
            'requests': accepted
                ? []
                : [
                    {
                      'id': 9,
                      'user': {'id': 3, 'username': 'noah'},
                      'createdAt': '2026-11-10',
                    },
                  ],
          };
        case 'POST /friend-requests/9/accept':
          accepted = true;
          body = {};
        default:
          body = {};
      }
      return http.Response(jsonEncode(body), 200);
    }),
  );

  setUp(() {
    calls.clear();
    accepted = false;
    FlutterSecureStorage.setMockInitialValues({'auth_token': 't'});
  });

  testWidgets('lists friends and requests, and accepting adds a friend', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FriendsScreen(
          api: api(),
          user: const UserAccount(id: 1, username: 'me', email: 'm@x.tn'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('@samira'), findsOneWidget);
    expect(find.text('Friends (1)'), findsOneWidget);
    expect(find.byKey(const ValueKey('request_9')), findsOneWidget);
    expect(find.byKey(const ValueKey('friends_share')), findsOneWidget);

    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();

    expect(calls, contains('POST /friend-requests/9/accept'));
    expect(find.text('Friends (2)'), findsOneWidget);
    expect(find.byKey(const ValueKey('request_9')), findsNothing);
  });
}
