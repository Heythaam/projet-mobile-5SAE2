/// Part of the day a match starts in.
enum DayPart {
  morning('Morning', 5, 12),
  afternoon('Afternoon', 12, 17),
  evening('Evening', 17, 21),
  night('Night', 21, 5);

  const DayPart(this.label, this.fromHour, this.toHour);

  final String label;

  /// The part starts at [fromHour] and ends before [toHour] (wrapping past
  /// midnight for the night).
  final int fromHour;
  final int toHour;

  bool contains(DateTime time) {
    final hour = time.hour;
    return fromHour < toHour
        ? hour >= fromHour && hour < toHour
        : hour >= fromHour || hour < toHour;
  }
}

/// What the player narrows the public matches down to. Every set field must
/// match; an empty filter keeps everything.
class MatchFilter {
  const MatchFilter({this.day, this.part, this.fromMinute});

  /// Only matches on this calendar day.
  final DateTime? day;

  /// Only matches starting in this part of the day.
  final DayPart? part;

  /// Only matches starting at or after this time, in minutes after midnight.
  final int? fromMinute;

  bool get isEmpty => day == null && part == null && fromMinute == null;

  MatchFilter copyWith({
    DateTime? day,
    DayPart? part,
    int? fromMinute,
    bool clearDay = false,
    bool clearPart = false,
    bool clearFromMinute = false,
  }) => MatchFilter(
    day: clearDay ? null : day ?? this.day,
    part: clearPart ? null : part ?? this.part,
    fromMinute: clearFromMinute ? null : fromMinute ?? this.fromMinute,
  );

  /// Whether a match starting at [start] (local time) passes the filter.
  bool allows(DateTime start) {
    final wanted = day;
    if (wanted != null &&
        (start.year != wanted.year ||
            start.month != wanted.month ||
            start.day != wanted.day)) {
      return false;
    }
    final wantedPart = part;
    if (wantedPart != null && !wantedPart.contains(start)) return false;
    final from = fromMinute;
    if (from != null && start.hour * 60 + start.minute < from) return false;
    return true;
  }
}
