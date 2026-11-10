import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:football_match_app/entities/match/match_mock_data.dart';
import 'package:football_match_app/items/match/match_widgets.dart';

void main() {
  final match = MatchHomeMatch(
    scheduledAt: DateTime(2026, 11, 14, 18),
    stadium: 'Green Arena',
    players: 3,
    capacity: 10,
    isPublic: true,
    code: 'ABCDE',
    playerSlots: const ['F', 'S', 'M', null, null, null, null, null, null, null],
  );

  Future<void> pumpRow(WidgetTester tester, {double? distanceKm}) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MatchRow(
              match: match,
              timeLabel: 'Sat',
              distanceKm: distanceKm,
              onJoin: () {},
            ),
          ),
        ),
      );

  testWidgets('shows only the stadium when there is no distance', (tester) async {
    await pumpRow(tester);
    expect(find.text('Green Arena'), findsOneWidget);
  });

  testWidgets('shows kilometres with one decimal', (tester) async {
    await pumpRow(tester, distanceKm: 3.26);
    expect(find.text('Green Arena · 3.3 km'), findsOneWidget);
  });

  testWidgets('shows metres under one kilometre', (tester) async {
    await pumpRow(tester, distanceKm: 0.42);
    expect(find.text('Green Arena · 420 m'), findsOneWidget);
  });
}
