class TournamentStats {
  const TournamentStats({
    required this.topScorers,
    required this.winRates,
    required this.totals,
  });

  final List<ScorerStat> topScorers;
  final Map<int, double> winRates;
  final TournamentTotals totals;

  factory TournamentStats.fromJson(Map<String, dynamic> json) {
    final scorersList = (json['topScorers'] as List<dynamic>? ?? const [])
        .map((item) => ScorerStat.fromJson(item as Map<String, dynamic>))
        .toList();

    final winRatesMap = <int, double>{};
    final rawWinRates = json['winRates'] as Map<String, dynamic>? ?? const {};
    for (final entry in rawWinRates.entries) {
      final teamId = int.tryParse(entry.key);
      if (teamId != null) {
        winRatesMap[teamId] = (entry.value as num).toDouble();
      }
    }

    final totalsMap =
        json['tournamentTotals'] as Map<String, dynamic>? ?? const {};
    return TournamentStats(
      topScorers: scorersList,
      winRates: winRatesMap,
      totals: TournamentTotals.fromJson(totalsMap),
    );
  }
}

class ScorerStat {
  const ScorerStat({
    required this.id,
    required this.name,
    required this.goals,
  });

  final int id;
  final String name;
  final int goals;

  factory ScorerStat.fromJson(Map<String, dynamic> json) => ScorerStat(
        id: json['id'] as int? ?? 0,
        name: json['name'] as String? ?? '',
        goals: json['goals'] as int? ?? 0,
      );
}

class TournamentTotals {
  const TournamentTotals({
    required this.totalGoals,
    required this.totalMatches,
    required this.averageGoalsPerMatch,
  });

  final int totalGoals;
  final int totalMatches;
  final double averageGoalsPerMatch;

  factory TournamentTotals.fromJson(Map<String, dynamic> json) =>
      TournamentTotals(
        totalGoals: json['totalGoals'] as int? ?? 0,
        totalMatches: json['totalMatches'] as int? ?? 0,
        averageGoalsPerMatch:
            (json['averageGoalsPerMatch'] as num?)?.toDouble() ?? 0.0,
      );
}
