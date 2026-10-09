import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:football_match_app/api_client.dart';
import 'package:football_match_app/auth_screen.dart';
import 'package:football_match_app/models.dart';

void main() {
  testWidgets('switches between sign in and account creation', (
    WidgetTester tester,
  ) async {
    UserAccount? signedInUser;
    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen(
          api: ApiClient(),
          onAuthenticated: (user) => signedInUser = user,
        ),
      ),
    );

    expect(find.text('You’re up.'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);

    final createAccountLink = find.text('New to the team? Create an account');
    await tester.ensureVisible(createAccountLink);
    await tester.tap(createAccountLink);
    await tester.pumpAndSettle();

    expect(find.text('Get in the game.'), findsOneWidget);
    expect(find.text('PLAYER NAME'), findsOneWidget);
    expect(find.text('Create my profile'), findsOneWidget);
    expect(signedInUser, isNull);
  });
}
