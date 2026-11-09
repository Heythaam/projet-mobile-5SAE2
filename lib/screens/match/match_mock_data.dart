// Match models for the screens. The stadium list below is sample data until
// the Stadium module has a player booking screen.

class MatchStadiumData {
  const MatchStadiumData({
    required this.name,
    required this.distance,
    required this.coins,
    required this.players,
    this.latitude,
    this.longitude,
  });

  final String name;
  final String distance;
  final int coins;
  final int players;
  final double? latitude;
  final double? longitude;
}

class MatchHomeMatch {
  const MatchHomeMatch({
    required this.scheduledAt,
    required this.stadium,
    required this.players,
    required this.capacity,
    required this.isPublic,
    required this.code,
    this.playerSlots = const [],
  });

  final DateTime scheduledAt;
  final String stadium;
  final int players;
  final int capacity;
  final bool isPublic;
  final String code;
  final List<String?> playerSlots;
}

class MatchPublicListing {
  const MatchPublicListing({
    required this.match,
    required this.timeLabel,
    required this.isToday,
    this.distanceKm,
  });

  final MatchHomeMatch match;
  final String timeLabel;
  final bool isToday;

  /// Kilometres from the player, when their location is on and the match has
  /// a place.
  final double? distanceKm;
}

class CreateMatchDraft {
  const CreateMatchDraft({
    required this.stadium,
    required this.startsAt,
    required this.visibility,
  });

  final MatchStadiumData stadium;
  final DateTime startsAt;
  final String visibility;
}

const matchStadiums = [
  MatchStadiumData(
    name: 'Green Arena',
    distance: '2 km',
    coins: 40,
    players: 10,
    latitude: 36.8190,
    longitude: 10.1658,
  ),
  MatchStadiumData(
    name: 'City Pitch',
    distance: '3.5 km',
    coins: 30,
    players: 8,
    latitude: 36.8065,
    longitude: 10.1815,
  ),
  MatchStadiumData(
    name: 'Sport Hall',
    distance: '5.2 km',
    coins: 25,
    players: 8,
    latitude: 36.8470,
    longitude: 10.2730,
  ),
  MatchStadiumData(
    name: 'Riverside Park',
    distance: '7.8 km',
    coins: 20,
    players: 10,
    latitude: 36.7480,
    longitude: 10.2100,
  ),
];
