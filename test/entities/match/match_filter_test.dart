import 'package:flutter_test/flutter_test.dart';
import 'package:football_match_app/entities/match/match_filter.dart';

void main() {
  test('an empty filter keeps every match', () {
    expect(const MatchFilter().isEmpty, isTrue);
    expect(const MatchFilter().allows(DateTime(2026, 12, 1, 3)), isTrue);
  });

  test('parts of the day cover the clock, night wraps past midnight', () {
    bool inPart(DayPart part, int hour) =>
        MatchFilter(part: part).allows(DateTime(2026, 12, 1, hour));
    expect(inPart(DayPart.morning, 8), isTrue);
    expect(inPart(DayPart.morning, 12), isFalse);
    expect(inPart(DayPart.afternoon, 12), isTrue);
    expect(inPart(DayPart.evening, 20), isTrue);
    expect(inPart(DayPart.night, 23), isTrue);
    expect(inPart(DayPart.night, 2), isTrue);
    expect(inPart(DayPart.night, 9), isFalse);
  });

  test('date and earliest start time must both match', () {
    final filter = MatchFilter(day: DateTime(2026, 12, 5), fromMinute: 18 * 60);
    expect(filter.allows(DateTime(2026, 12, 5, 19)), isTrue);
    expect(filter.allows(DateTime(2026, 12, 5, 17, 59)), isFalse);
    expect(filter.allows(DateTime(2026, 12, 6, 19)), isFalse);
  });

  test('copyWith can clear single fields', () {
    final filter = MatchFilter(
      day: DateTime(2026, 12, 5),
      part: DayPart.night,
      fromMinute: 600,
    ).copyWith(clearPart: true);
    expect(filter.part, isNull);
    expect(filter.day, isNotNull);
    expect(filter.fromMinute, 600);
  });
}
