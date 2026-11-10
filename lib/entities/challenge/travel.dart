/// How long it takes to reach a place from where the player is.
class TravelEstimate {
  const TravelEstimate({
    required this.driveMinutes,
    required this.walkMinutes,
    required this.kilometres,
  });

  final int driveMinutes;
  final int walkMinutes;

  /// Road distance by car.
  final double kilometres;

  static String format(int minutes) => minutes < 60
      ? '$minutes min'
      : '${minutes ~/ 60} h ${(minutes % 60).toString().padLeft(2, '0')}';
}

/// Either an estimate or a message ready to show the player.
class TravelResult {
  const TravelResult.ok(TravelEstimate this.estimate) : message = null;
  const TravelResult.failed(String this.message) : estimate = null;

  final TravelEstimate? estimate;
  final String? message;
}
