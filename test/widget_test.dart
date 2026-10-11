import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:football_match_app/api_client.dart';
import 'package:football_match_app/auth_screen.dart';
import 'package:football_match_app/matches/football_match.dart';
import 'package:football_match_app/matches/match_repository.dart';
import 'package:football_match_app/models.dart';
import 'package:football_match_app/screens/calendar_screen.dart';
import 'package:football_match_app/screens/kickoff_shell.dart';

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

    expect(find.text('Sign in'), findsOneWidget);
    final createAccountLink = find.text('New here? Sign up');
    await tester.ensureVisible(createAccountLink);
    await tester.tap(createAccountLink);
    await tester.pumpAndSettle();

    expect(find.text('Player name'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Have an account? Sign in'), findsOneWidget);
    expect(signedInUser, isNull);
  });

  testWidgets('shell switches between home, calendar, and profile', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_shell());
    await tester.pumpAndSettle();

    expect(find.text('Create'), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    expect(
      tester.getRect(find.byIcon(Icons.add_rounded)).center.dx,
      closeTo(tester.getRect(find.text('Create')).center.dx, 1),
    );
    expect(find.bySemanticsLabel('Calendar'), findsOneWidget);
    expect(find.bySemanticsLabel('Open ball menu'), findsOneWidget);
    expect(find.bySemanticsLabel('Profile'), findsOneWidget);
    expect(find.text('Calendar'), findsNothing);
    expect(find.text('Profile'), findsNothing);
    await tester.tap(find.bySemanticsLabel('Calendar'));
    await tester.pumpAndSettle();
    expect(find.text('No matches yet'), findsOneWidget);
    expect(find.byIcon(Icons.calendar_month_rounded), findsNWidgets(2));

    await tester.tap(find.bySemanticsLabel('Calendar'));
    await tester.pumpAndSettle();
    expect(find.text('Create'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Profile'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Awards'), findsOneWidget);
    expect(find.text('Friends'), findsOneWidget);
  });

  testWidgets('ball menu opens and closes', (WidgetTester tester) async {
    await tester.pumpWidget(_shell());
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Open ball menu'));
    await tester.pumpAndSettle();

    expect(find.text('Challenge'), findsOneWidget);
    expect(find.text('Match'), findsOneWidget);
    expect(find.text('Tournament'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Close ball menu'));
    await tester.pumpAndSettle();

    expect(find.text('Challenge'), findsNothing);
    expect(find.text('Create'), findsOneWidget);
  });

  testWidgets('shell fits phone sizes and text scales without clipping', (
    WidgetTester tester,
  ) async {
    for (final size in const [Size(360, 640), Size(393, 852), Size(412, 915)]) {
      for (final textScale in const [1.0, 1.3]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(top: 24);
        tester.view.viewPadding = const FakeViewPadding(top: 24);
        await tester.pumpWidget(
          _shell(key: ValueKey('$size-$textScale'), textScale: textScale),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(
          tester.getTopLeft(find.text('NEXT')).dy,
          greaterThanOrEqualTo(34),
        );

        await tester.tap(find.bySemanticsLabel('Calendar'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          tester
              .getTopLeft(
                find.textContaining(
                  RegExp(
                    r'January|February|March|April|May|June|July|August|September|October|November|December',
                  ),
                ),
              )
              .dy,
          greaterThanOrEqualTo(34),
        );

        await tester.tap(find.bySemanticsLabel('Profile'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          tester.getTopLeft(find.text('@player')).dy,
          greaterThanOrEqualTo(34),
        );
        expect(tester.getTopLeft(find.text('P')).dy, greaterThanOrEqualTo(34));
        expect(
          tester.getRect(find.byKey(const ValueKey('profile_avatar'))).height,
          closeTo(96 * (size.width / 360).clamp(1.0, 1.3), 0.1),
        );
        expect(
          tester.getTopRight(find.byTooltip('Settings')).dx,
          lessThanOrEqualTo(size.width - 12),
        );
      }
    }
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
  });

  testWidgets('sign-up form scrolls with keyboard and keeps CTA after fields', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen(api: ApiClient(), onAuthenticated: (_) {}),
      ),
    );
    await tester.pumpAndSettle();

    final signUpLink = find.text('New here? Sign up');
    await tester.ensureVisible(signUpLink);
    await tester.tap(signUpLink);
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(4));
    await tester.ensureVisible(fields.last);
    await tester.tap(fields.last);
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('auth_submit')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('auth_submit'))).dy -
          tester.getBottomLeft(fields.last).dy,
      greaterThanOrEqualTo(16),
    );
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
  });

  testWidgets('calendar filters matches and toggles past history', (
    WidgetTester tester,
  ) async {
    final now = DateTime.now();
    final matches = [
      FootballMatch(
        id: 'created',
        scheduledAt: now.add(const Duration(days: 1)),
        stadium: 'Created Pitch',
        joinedSlots: 3,
        totalSlots: 8,
        isPublic: true,
        participation: MatchParticipation.created,
      ),
      FootballMatch(
        id: 'joined',
        scheduledAt: now.add(const Duration(days: 2)),
        stadium: 'Joined Pitch',
        joinedSlots: 5,
        totalSlots: 8,
        isPublic: false,
        participation: MatchParticipation.joined,
      ),
      FootballMatch(
        id: 'past',
        scheduledAt: now.subtract(const Duration(days: 1)),
        stadium: 'Past Pitch',
        joinedSlots: 8,
        totalSlots: 8,
        isPublic: true,
        participation: MatchParticipation.created,
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CalendarScreen(
            matches: matches,
            loading: false,
            loadError: null,
            onRetry: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Created Pitch'), findsOneWidget);
    expect(find.text('Joined Pitch'), findsOneWidget);
    expect(find.text('Past Pitch'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Created matches'));
    await tester.pumpAndSettle();
    expect(find.text('Created Pitch'), findsOneWidget);
    expect(find.text('Joined Pitch'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Show past matches'));
    await tester.pumpAndSettle();

    expect(find.text('PAST'), findsOneWidget);
    expect(find.text('Past Pitch'), findsOneWidget);
    expect(find.text('Created Pitch'), findsOneWidget);
  });
}

Widget _shell({Key? key, double textScale = 1}) => MaterialApp(
  key: key,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: KickoffShell(
    api: _FakeApiClient(),
    user: const UserAccount(id: 1, username: 'player', email: 'p@example.com'),
    onLogout: () {},
    matchRepository: const EmptyMatchRepository(),
  ),
);

class _FakeApiClient extends Fake implements ApiClient {
  @override
  Future<GamificationProfile> getGamificationProfile() async =>
      const GamificationProfile(
        xp: 0,
        level: 1,
        rank: 'Rookie',
        xpIntoLevel: 0,
        xpForNextLevel: 100,
        currentStreak: 0,
        bestStreak: 0,
        sentMessages: 0,
        achievements: [],
      );
}
