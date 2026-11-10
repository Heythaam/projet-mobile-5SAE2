import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:football_match_app/api_client.dart';
import 'package:football_match_app/models.dart';
import 'package:football_match_app/users/choose_username_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the username must be free before the player moves on', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 't'});
    UserAccount? done;
    final api = ApiClient(
      baseUrl: 'http://api.test',
      client: MockClient((request) async {
        final name = (jsonDecode(request.body) as Map)['username'] as String;
        if (name == 'taken') {
          return http.Response(
            jsonEncode({'error': 'That username is already taken.'}),
            409,
          );
        }
        return http.Response(
          jsonEncode({
            'id': 1,
            'username': name,
            'email': 'a@x.tn',
            'usernameChosen': true,
          }),
          200,
        );
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ChooseUsernameScreen(
          api: api,
          onDone: (user) => done = user,
          onLogout: () {},
        ),
      ),
    );

    final field = find.descendant(
      of: find.byKey(const ValueKey('choose_username')),
      matching: find.byType(TextField),
    );
    final submit = find.byKey(const ValueKey('choose_username_submit'));

    await tester.enterText(field, 'ab');
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.textContaining('3-20 letters'), findsOneWidget);
    expect(done, isNull);

    await tester.enterText(field, 'taken');
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('That username is already taken.'), findsOneWidget);
    expect(done, isNull);

    await tester.enterText(field, 'fresh_name');
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(done?.username, 'fresh_name');
  });
}
