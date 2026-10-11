/// A knockout round from `GET /tournaments/:id/bracket`.
class BracketRound {
  const BracketRound({
    required this.round,
    required this.roundsFromEnd,
    required this.matches,
  });

  final int round;

  /// 0 for the final, 1 for the semi-finals, and so on.
  final int roundsFromEnd;

  /// Every slot of the round, in bracket order.
  final List<BracketMatch> matches;

  factory BracketRound.fromJson(Map<String, dynamic> json) => BracketRound(
    round: json['round'] as int,
    roundsFromEnd: json['roundsFromEnd'] as int,
    matches: (json['matches'] as List<dynamic>)
        .map((item) => BracketMatch.fromJson(item as Map<String, dynamic>))
        .toList(),
  );
}

enum BracketMatchStatus {
  scheduled('scheduled'),
  played('played'),
  cancelled('cancelled'),

  /// The home team advances without playing.
  bye('bye'),

  /// A slot with no match yet; its teams may already be known.
  pending('pending');

  const BracketMatchStatus(this.apiValue);

  final String apiValue;

  static BracketMatchStatus fromApi(String value) => values.firstWhere(
    (status) => status.apiValue == value,
    orElse: () => throw FormatException('Unknown match status: $value'),
  );
}

class BracketTeam {
  const BracketTeam({required this.id, required this.name});

  final int id;
  final String name;

  factory BracketTeam.fromJson(Map<String, dynamic> json) =>
      BracketTeam(id: json['id'] as int, name: json['name'] as String);
}

class BracketMatch {
  const BracketMatch({
    required this.position,
    required this.status,
    this.id,
    this.home,
    this.away,
    this.homeScore,
    this.awayScore,
    this.winnerId,
    this.scheduledAt,
  });

  /// Null for a slot that has no match row yet.
  final int? id;

  /// 1-based slot within the round.
  final int position;

  /// Null while the team is still to be determined.
  final BracketTeam? home;
  final BracketTeam? away;
  final int? homeScore;
  final int? awayScore;
  final BracketMatchStatus status;
  final int? winnerId;
  final DateTime? scheduledAt;

  bool get isBye => status == BracketMatchStatus.bye;

  /// A played draw whose winner was decided on penalties.
  bool get wonOnPenalties =>
      status == BracketMatchStatus.played &&
      homeScore != null &&
      homeScore == awayScore &&
      winnerId != null;

  BracketTeam? get winner => switch (winnerId) {
    null => null,
    final id when home?.id == id => home,
    final id when away?.id == id => away,
    _ => null,
  };

  factory BracketMatch.fromJson(Map<String, dynamic> json) => BracketMatch(
    id: json['id'] as int?,
    position: json['position'] as int,
    status: BracketMatchStatus.fromApi(json['status'] as String),
    home: switch (json['home']) {
      final Map<String, dynamic> team => BracketTeam.fromJson(team),
      _ => null,
    },
    away: switch (json['away']) {
      final Map<String, dynamic> team => BracketTeam.fromJson(team),
      _ => null,
    },
    homeScore: json['homeScore'] as int?,
    awayScore: json['awayScore'] as int?,
    winnerId: json['winnerId'] as int?,
    scheduledAt: switch (json['scheduledAt']) {
      final String value => DateTime.tryParse(value),
      _ => null,
    },
  );
}
