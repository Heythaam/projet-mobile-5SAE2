/// Sunrise and sunset at one place on one day, in the phone's local time.
class Daylight {
  const Daylight({required this.sunrise, required this.sunset});

  final DateTime sunrise;
  final DateTime sunset;

  /// How a game from [start] for [minutes] sits against the daylight.
  DaylightVerdict verdict(DateTime start, int minutes) {
    final end = start.add(Duration(minutes: minutes));
    if (!start.isBefore(sunset) || end.isBefore(sunrise)) {
      return DaylightVerdict.dark;
    }
    if (start.isBefore(sunrise) || end.isAfter(sunset)) {
      return DaylightVerdict.partlyDark;
    }
    return DaylightVerdict.daylight;
  }
}

enum DaylightVerdict {
  daylight('Played in full daylight'),
  partlyDark('Ends after dark: pick a pitch with floodlights'),
  dark('After dark: floodlights needed');

  const DaylightVerdict(this.label);

  final String label;
}
