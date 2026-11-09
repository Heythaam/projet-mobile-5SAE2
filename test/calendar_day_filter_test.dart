import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:football_match_app/matches/football_match.dart';
import 'package:football_match_app/screens/calendar_screen.dart';

void main() {
  testWidgets('tapping a day lists only that day, again shows all', (
    tester,
  ) async {
    final today = DateTime.now().add(const Duration(minutes: 1));
    final matches = [
      FootballMatch(
        id: 'a',
        scheduledAt: today,
        stadium: 'Today Pitch',
        joinedSlots: 2,
        totalSlots: 8,
        isPublic: true,
        participation: MatchParticipation.created,
      ),
      FootballMatch(
        id: 'b',
        scheduledAt: today.add(const Duration(days: 3)),
        stadium: 'Later Pitch',
        joinedSlots: 2,
        totalSlots: 8,
        isPublic: true,
        participation: MatchParticipation.joined,
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
    expect(find.text('Today Pitch'), findsOneWidget);
    expect(find.text('Later Pitch'), findsOneWidget);

    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final label = '${names[today.weekday - 1]} ${today.day}';
    await tester.tap(find.bySemanticsLabel(RegExp('^$label')));
    await tester.pumpAndSettle();
    expect(find.text('Today Pitch'), findsOneWidget);
    expect(find.text('Later Pitch'), findsNothing);

    await tester.tap(find.bySemanticsLabel(RegExp('^$label')));
    await tester.pumpAndSettle();
    expect(find.text('Later Pitch'), findsOneWidget);
  });
}
